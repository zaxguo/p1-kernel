$(TARGETLIB): $(OBJS)
	@rm -f $@
	@ar rc $@ $(OBJS)
	@ranlib $@
	@mkdir -p $(LIB_BUILD_PATH)
	cp -f $(TARGETLIB) $(LIB_BUILD_PATH)