# frozen_string_literal: true

needs 'OLASimple/OLAConstants'
needs 'OLASimple/OLALib'
needs 'OLASimple/OLAGraphics'
needs 'OLASimple/JobComments'
needs 'OLASimple/OLAKitIDs'


class Protocol

    include OLAConstants
    include OLALib
    include OLAGraphics
    include JobComments
    include OLAKitIDs


  ##########################################
  # INPUT/OUTPUT
  ##########################################
    INPUT = 'Patient Sample'
    #OUTPUT = 'cDNA'
    OUTPUT = 'Patient Sample'
    PACK = 'RT Pack'
    
    
  ##########################################
  # TERMINOLOGY
  ##########################################

  ##########################################
  # Protocol Specifics
  ##########################################
    
    PACK_HASH = RT_UNIT
    AREA = PRE_PCR
    SAMPLE_VOLUME = 20 # volume of sample to add to PCR mix
    CENTRIFUGE_TIME = '5 seconds' # time to pulse centrifuge to pull down dried powder
    VORTEX_TIME = '5 seconds' # time to pulse vortex to mix

    TUBE_CAP_WARNING = 'Check to make sure tube caps are completely closed.'
    MATERIALS = [
        'P20 pipette and filtered tips',
        'Gloves (wear tight gloves to reduce contamination risk)',
        'Centrifuge',
        '70% v/v Ethanol spray for cleaning',
        '10% v/v Bleach spray for cleaning',
        'Molecular grade ethanol'
    ].freeze

    SAMPLE_ALIAS = 'RNA Extract'
    
      # for debugging and tests
      PREV_COMPONENT = '6'
      PREV_UNIT = 'E'

  
    def main
        
        operations.running.retrieve interactive: false
        operations.running.make
        save_user operations

        if debug
          labels = %w[001 002]
          kit_num = 'K001'
          operations.each.with_index do |op, i|
            op.input(INPUT).item.associate(SAMPLE_KEY, labels[i])
            op.input(INPUT).item.associate(COMPONENT_KEY, PREV_COMPONENT)
            op.input(INPUT).item.associate(KIT_KEY, kit_num)
            op.input(INPUT).item.associate(UNIT_KEY, PREV_UNIT)
            op.input(INPUT).item.associate(PATIENT_KEY, "A PATIENT ID")        
          end #each with index
        end #if debug
        
        save_temporary_input_values(operations, INPUT)

        
        operations.each do |op|
            op.temporary[:pack_hash] = PACK_HASH
        end # operations each do for PACK_HASH
        
        save_temporary_output_values(operations) # defined in olalib

        run_checks(operations)
        kit_introduction(operations.running)

        
        record_technician_id
        safety_warning
        area_preparation('pre-PCR', MATERIALS, POST_PCR)
        simple_clean("OLASimple RT Module")


        get_incoming_samples(operations.running) #get tubes from previous op
        validate_incoming_samples(operations.running) # check tubes from previous op
        
        show do
            note "now get kit"
        end
        
        retrieve_kit_packages(operations.running) # get kit for RT procedure
        validate_kit_packages(operations.running) #check tubes for RT procedure
        
        show do
            note "now open kit and check that it's correct"
        end 
        
        open_kit_packages(operations.running)
        
        centrifuge_samples(operations.running)
        
        transfer_samples(operations.running)
        
        start_thermocycler(operations.running)
        

    end #main
    
    #######################################
    # Instructions
    #######################################

    def kit_introduction(ops)
        show do
            title "Welcome to OLASimple RT (Reverse Transcription)"
            note 'In this protocol you will be converting the RNA generated from the E module into cDNA'
        end # welcome block

        show do
            title 'RNase degrades RNA'
            note 'RNA is prone to degradation by RNase present in our eyes, skin, and breath.'
            note 'Avoid opening tubes outside the Biosafety Cabinet (BSC).'
            bullet 'Change gloves whenever you suspect potential RNAse contamination'
        end # RNase warning block
    end # kit_introduction
    
    
    def get_incoming_samples(myops)
        # get the results of the extraction
        gops = group_packages(myops)
        show do
            title "Place #{SAMPLE_ALIAS.bold} samples in #{AREA.bold} area."
            note "In #{AREA.bold} area, retrieve tubes from thermocycler and place into a rack."
            tubes = []
            gops.each do |unit, ops|
                ops.each_with_index do |op, i|
                    tubes << make_tube(closedtube, '', ref(op.input(INPUT).item).split('-'), 'medium', true).translate!(100 * i)
                end # each with index, create tube images and add to array

                img = SVGElement.new(children: tubes, boundy: 300, boundx: 300).translate!(20) # create image
                note display_svg(img) # display image -- method from image library
            end # gops each do
        end # show block
    end #method

    def validate_incoming_samples(myops)
        expected_inputs = myops.map { |op| ref(op.input(INPUT).item) }
        sample_validation_with_multiple_tries(expected_inputs)
    end

    def retrieve_kit_packages(myops)
        gops = group_packages(myops)
        show do
        title "Take #{RT_PKG_NAME.pluralize(gops.length)} from the #{FRIDGE_PRE} with a Paper Towel and place on the #{BENCH_POST}"
            gops.each do |unit, _ops|
                check "unit is #{unit}"
                check "Take package #{unit.bold} from fridge."
                check "Place package #{unit.bold} on the bench."
            end # take and place block
        end # show block
    end # method   
    
    def validate_kit_packages(myops)
    # unit here is the package -- this_package
        group_packages(myops).each { |unit, _ops| package_validation_with_multiple_tries(unit) }
    end
    
    
    
    def open_kit_packages(myops)
        grouped_by_unit = myops.group_by { |op| op.temporary[:output_kit_and_unit] }
        
        grouped_by_unit.each do |kit_and_unit, ops|
            show do
                note "kit and unit is #{kit_and_unit}"
            end
        end
            # ops.each do |op|
            #     op.make_item_and_alias(OUTPUT, 'sample tube', INPUT)
            # end # ops each do
        # inthis case there are no subpackages
        # show_open_package(kit_and_unit, '', ops.first.temporary[:pack_hash][NUM_SUB_PACKAGES_FIELD_VALUE]) do
        # rt_tube_labels = ops.map { |op| op.output_tube_label(OUTPUT) }
        # num_samples = ops.first.temporary[:pack_hash][NUM_SAMPLES_FIELD_VALUE]
        # kit, unit, component, sample = ops.first.output_tokens(OUTPUT)

        # grid = SVGGrid.new(num_samples, 1, 75, 10)
        # rt_tube_labels.each_with_index do |tube_label, i|
        #   # powder is saying how to describe what's in the tube
        #   rt_tube = make_tube(closedtube, '', tube_label, 'powder', true).scale(0.75)
        #   grid.add(rt_tube, i, 0)
        # end #end each wit index

        # grid.boundy = closedtube.boundy * 0.75
        # grid.align_with(diluentATube, 'center-right')
        # grid.align!('center-left')
        # grid.translate!(25, 25)
        # img = SVGElement.new(children: [diluentATube, grid], boundy: diluentATube.boundy + 50, boundx: 300).translate!(20)

        # check "Look for #{num_samples + 1} #{'tube'.pluralize(num_samples)}"
        # check 'Place tubes on a rack'
        # note display_svg(img, 0.75)
    #   end #show_open_package do
    # end #grouped by unit
  end #method



    def centrifuge_samples(ops)
        #labels = ops.map { |op| ref(op.output(OUTPUT).item) }
        show do
          title 'Centrifuge all samples for 5 seconds'
          check 'Place all tubes and samples in the centrifuge, along with a balancing tube. It is important to balance the tubes.'
          check 'Centrifuge the tubes for 5 seconds to pull down liquid and dried reagents'
        end
    end # centrifuge samples

    def transfer_samples(myops)
        gops = group_packages(myops)

        gops.each do |_unit, ops|
          samples = ops.map { |op| op.input(INPUT).item }
          sample_refs = samples.map { |sample| ref(sample) }
          
          show do
              note "samples are #{samples} and sample_refs are #{sample_refs}"
              # samples refs are correct E6-001 and E6-002
          end # inner show block for testing

          ops.each do |op|
            from = ref(op.input(INPUT).item)
            to = ref(op.output(OUTPUT).item)
            show do
                note "from is #{from}"
                note "to is #{to}"
            end
            # tubeS = make_tube(opentube, [SAMPLE_ALIAS, from], '', fluid = 'medium')
            tubeS = make_tube(opentube, [from], '', fluid = 'medium')
            tubeP = make_tube(opentube, ["RT number goes here", to], '', fluid = 'medium').scale!(0.75)
            #tubeS_closed = make_tube(closedtube, [SAMPLE_ALIAS, from], '', fluid = 'medium')
            tubeS_closed = make_tube(closedtube, [from], '', fluid = 'medium')
            tubeP_closed = make_tube(closedtube, ["RT number goes here", to], '', fluid = 'medium').translate!(0,40).scale!(0.75)

            #pre_transfer_validation_with_multiple_tries(from, to, tubeS_closed, tubeP_closed)

                show do
                  raw transfer_title_proc(SAMPLE_VOLUME, "#{from}", "RT NUMBER GOES HERE #{to}")
                  
                  note "part that follows transfer_title_proc call"
                  note "#{from} will be used to dissolve the lyophilized RT mixture."
                  note "Carefully open tube #{from.bold} and tube <RT NUMBER GOES HERE> #{to.bold}" # should be RT tube with number
                  note "Use a #{P20_PRE} pipette and set it to <b>[2 0 0]</b>."
                  check "Transfer #{SAMPLE_VOLUME}uL from #{from.bold} into RT NUMBER GOES HERE #{to.bold}" # same should be RT tube with number
                  
                  
                  img = make_transfer(tubeS, tubeP, 300, "#{SAMPLE_VOLUME}uL", "(#{P20_PRE} pipette)")
                  img.translate!(25)
                  note display_svg(img, 0.75)
                  check 'Close tubes and discard pipette tip'
                end # show block
            end #ops each do
        end #end gops each do
    end #method
    
    
    def start_thermocycler(ops)
        # Adds the RT tubes to the thermocycler.
        # Instructions for RT cycles.
        #
        samples = ops.map { |op| op.output(OUTPUT).item }
        sample_refs = samples.map { |sample| ref(sample) }

        vortex_and_centrifuge_helper("RT TUBES",
                                     sample_refs,
                                     VORTEX_TIME, CENTRIFUGE_TIME,
                                     'to mix.', 'to pull down liquid', AREA, mynote = nil)
    
        t = Table.new
    
        t.add_column('STEP', ['RT Step'])
        t.add_column('TEMP', ['55C'])
        t.add_column('TIME', ['10 min'])

        show do
          title 'Run RT Reaction'
          check 'Close all the lids of the pipette tip boxes and pre-PCR rack'
          check "Take only the RT tubes (#{sample_refs.to_sentence}) with you"
          check 'Place the RT samples in the assigned thermocycler, close, and tighten the lid'
          check "Select the program named NAME OF PROGRAM TK under OS"
          check "Hit #{'Run'.quote} and #{'OK to 20uL'.quote}"
          table t
        end # show block for reaction

        operations.each do |op|
          op.output(OUTPUT).item.move THERMOCYCLER
        end # ops each do
    end # method 

    
    
  #######################################
  # Utilities
  #######################################
  def save_user(ops)
    ops.each do |op|
      username = get_technician_name(jid)
      op.associate(:technician, username)
    end
  end #save_user
  
    def run_checks(_myops)
        if operations.running.empty?
            show do
                title 'All operations have errored'
                note "Contact #{SUPERVISOR}"
        operations.each do |op|
          note (op.errors.map { |k, v| [k, v] }).to_s
        end
      end
      {}
    end
  end #run_checks



end #class

